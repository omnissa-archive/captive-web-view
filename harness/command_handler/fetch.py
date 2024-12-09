# Copyright 2023 Omnissa, LLC.  
# SPDX-License-Identifier: BSD-2-Clause
"""\
Captive Web View python harness command handler for the fetch command.

Import and use it like the ../../captivityHarness/__main__.py server does."""
#
# Standard library imports, in alphabetic order.
# Module for HTTP server, not imported here but handy to have the link.
# https://docs.python.org/3/library/http.server.html
#
# Module for Base 64 encoding certificate DER data.
# https://docs.python.org/3/library/base64.html
import base64
#
# Cryptographic hash module. Only used to generate a certificate thumbprint.
# https://docs.python.org/3/library/hashlib.html
import hashlib
#
# HTTP modules.
# https://docs.python.org/3/library/http.client.html#http.client.HTTPSConnection
from http.client import HTTPSConnection
# Also for reference but without explicit imports.
# https://docs.python.org/3/library/http.client.html#httpresponse-objects
#
# JSON module.
# https://docs.python.org/3/library/json.html
import json
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module for socket connections. Only used to generate a wrap-able socket for a
# TLS connection so that the peer certificate can be obtained.
# https://docs.python.org/3/library/socket.html
import socket
#
# Module for creating an unverified SSL/TLS context.
# Uses the undocumented _create_unverified_context() interface.
# TOTH https://stackoverflow.com/a/50949266/7657675
import ssl
#
# Module for spawning a process to run a command.
# https://docs.python.org/3/library/subprocess.html
import subprocess
#
# Module for manipulation of the import path.
# https://docs.python.org/3/library/sys.html#sys.path
import sys
#
# Temporary file module.
# https://docs.python.org/3/library/tempfile.html
from tempfile import NamedTemporaryFile
#
# URL parsing module.
# https://docs.python.org/3/library/urllib.parse.html#urllib.parse.urlparse
from urllib.parse import urlparse
#
# Local Imports.
#
# Command handler base class.
from .base import CommandHandler

class Fetcher:
    _rootPath = Path().resolve().root
    # TOTH macOS `security` CLI and how to export the system CA stores:
    # https://stackoverflow.com/a/72053605/7657675
    _keychains = (
        (
            _rootPath, 'System', 'Library', 'Keychains'
            , 'SystemRootCertificates.keychain'
        ), (
            _rootPath, 'Library', 'Keychains', 'System.keychain'
        )
    )

    def __init__(self):
        self._pemPath = self.keychain_PEM()

        # Create a context in which the certificates from the keychain will be
        # used to verify the host.
        self._sslContext = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        self._sslContext.load_verify_locations(self._pemPath)

        # Note that host verification has to be switched on here for the peer
        # certificate to be available later, when the secure socket is
        # connected. Also, the host certificate has to be valid. For later
        # maybe, use something from this SO answer to get the certificate even
        # if it isn't valid.
        # https://stackoverflow.com/a/7691293/7657675

        # The sslContext no longer requires the PEM file but it's used later by
        # the openssl s_client.
        # self._pemPath.unlink()

    def keychain_PEM(self):
        # Export all the certificates from the system keychains into a single
        # temporary PEM file. Return the Path of the file.
        #
        # TOTH macOS `security` CLI and how to export the system CA stores:
        # https://stackoverflow.com/a/72053605/7657675
        #
        # TOTH creating a temporary file instead of loading it in the bash
        # profile:  
        # https://stackoverflow.com/a/70054211/7657675
        with NamedTemporaryFile(mode='w', delete=False, suffix=".pem") as file:
            pemPath = Path(file.name)

        for keychain in self._keychains:
            keychainPath = Path(*keychain)
            # TOTH macOS `security` CLI and how to export the system CA stores:
            # https://stackoverflow.com/a/72053605/7657675
            securityRun = subprocess.run(
                (
                    'security', 'export', '-k', keychainPath, '-t', 'certs'
                    , '-f', 'pemseq'
                ), stdout=subprocess.PIPE, text=True
            )
            print(f'"{keychainPath}" PEM {len(securityRun.stdout)} characters.')
            with pemPath.open('a') as file:
                file.write(securityRun.stdout)

        certificates = 0
        with pemPath.open() as file:
            while True:
                line = file.readline()
                if line == '':
                    break
                if line.startswith('--') and 'BEGIN CERTIFICATE' in line:
                    certificates += 1
        print(f'Keychain certificates: {certificates}.')

        return pemPath

# Returns a 404 and empty body.
# https://httpbin.org/status/404
#
# Returns a JSON object.
# https://httpbin.org/get
#
# Returns a 400 and error message in HTML.
# https://client.badssl.com/
#
# Returns a 404 and the usual front page HTML. Note that 404 isn't a special
# value for the example.com server.  
# https://example.com/404

    def fetch(self, parameters, httpHandler=None):
        return_ = {
            'peerCertificate': { 'DER': None, 'length': None },
            "text": None, "json": None, "ok": False
        }

        url, port, parameterError = self._parse_resource(parameters)
        if parameterError is not None:
            return_['status'] = 0
            return_.update(parameterError)
            return return_
        self._log(httpHandler, f'fetch() {url.hostname} {port}.')

        connection, connectError = self._connect(url.hostname, port)
        if connectError is not None:
            return_['status'] = 1
            return_.update(connectError)
            return return_

        (
            return_['peerCertificate']['DER'],
            return_['peerCertificate']['length']
        ) = self.get_peer_certificate(connection, httpHandler)

        return_['text'], details = self._request(
            connection, parameters, httpHandler)
        connection.close()
 
        return_['json'], jsonError = self._parse_JSON(return_['text'])

        if details['ok']:
            if jsonError is None:
                return_.update(details)
            else:
                return_['status'] = 2
                return_.update(jsonError)
        else:
            return_.update(details)

        # As an additional manual check, dump the thumbprint with the openssl
        # CLI.
        #
        # url.netloc includes port, if there was one in the URL.
        self.openssl_thumbprint(
            url.hostname
            , f'{url.hostname}:{port}' if url.port is None else url.netloc
            , httpHandler)
        
        return return_

    def _parse_resource(self, parameters):
        try:
            resource = parameters['resource']
        except KeyError:
            return None, None, {
                'statusText': 'No "resource" in parameters.',
                'headers': {
                    'parameterKeys': tuple(parameters.keys())
                }
            }

        url = urlparse(resource)
        if url.hostname is None:
            return None, None, {
                'statusText': "No host in parameters.resource",
                'headers': { 'resource': resource, 'url': f'{url}'}
            }

        return url, 443 if url.port is None else url.port, None

    def _connect(self, host, port):
        def return_(error, stage):
            return {
                'statusText': error.__class__.__name__,
                'headers': {
                    'host': host,
                    'port': port,
                    'args': error.args,
                    'message':f'{error}',
                    'stage': stage
                }
            }

        try:
            connection = HTTPSConnection(
                host, port=port, context=self._sslContext)
        except Exception as error:
            return None, return_(error, 'HTTPSConnection()')

        try:
            connection.connect()
        except Exception as error:
            return None, return_(error, 'connect()')
        
        return connection, None

    def get_peer_certificate(self, connection, httpHandler):
        # The connection.sock property mightn't be documented but seems safe.
        peerCertBinary = connection.sock.getpeercert(True)
        peerCertDict = connection.sock.getpeercert(False)

        peerCertLength = len(peerCertBinary)
        peerCertMessage = "\n".join([
            f'{key} "{value}"' for key, value in peerCertDict.items()
        ])
        self._log(httpHandler
            , f'Peer certificate. Binary length: {peerCertLength}'
            f'. Dictionary:\n{peerCertMessage}')

        # TOTH Generate fingerprint with openssl and Python:
        # https://stackoverflow.com/q/70781380/7657675
        peerThumb = hashlib.sha1(peerCertBinary).hexdigest()
        self._log(httpHandler, f'Peer certificate thumbprint:\n{peerThumb}')
        # www.python.org SHA1 Fingerprint=B0:9E:C3:40:F4:19:78:D7:7A:76:84:79:0A:EF:84:0E:AD:DA:49:FD
        # B09EC340F41978D77A7684790AEF840EADDA49FD
        # b09ec340f41978d77a7684790aef840eadda49fd

        return base64.b64encode(peerCertBinary).decode('utf-8'), peerCertLength

    def _request(self, connection, parameters, httpHandler):
        options = parameters.get('options', {})
        method = options.get('method', 'GET')
        # If the 'resource' key is missing the code won't reach this point. That
        # key is checked for in _parse_resource() before connecting even.
        resource = parameters['resource']
        self._log(httpHandler, f'putrequest\n({method},{resource})')
        connection.putrequest(method, resource)

        def put_header(header, value):
            self._log(httpHandler, f'putheader\n({header},{value})')
            connection.putheader(header, value)

        for header, value in options.get('headers', {}).items():
            put_header(header, value)

        # Assume any body is JSON for now.
        if 'body' in options or 'bodyObject' in options:
            put_header('Content-Type', "application/json")

        body = (
            options['body'].encode() if 'body' in options
            else json.dumps(options['bodyObject']).encode()
            if 'bodyObject' in options
            else b'')
        put_header('Content-Length', len(body))
        connection.endheaders()

        self._log(httpHandler, f'send\n({body})')
        connection.send(body)
        response = connection.getresponse()

        # ToDo: Make it handle different encoding schemes instead of assuming
        # utf-8.
        return response.read().decode('utf-8'), {
            'ok': response.status >= 200 and response.status <= 299,
            'status': response.status,
            'statusText': response.reason,
            'headers': dict(response.getheaders())
        }

    def _parse_JSON(self, raw):
        if raw is None:
            raw = ""

        try:
            return json.loads(raw), None
        except json.decoder.JSONDecodeError as error:
            # https://docs.python.org/3/library/json.html#json.JSONDecodeError
            return None, {
                'statusText': error.__class__.__name__,
                'headers': {
                    'msg':error.msg,
                    'lineno': error.lineno, 'colno': error.colno
                }}

    def openssl_thumbprint(self, serverName, connectAddress, httpHandler):
        # TOTH Generate fingerprint with openssl and Python:
        # https://stackoverflow.com/q/70781380/7657675
        #
        # TOTH Terminate openssl client:
        # https://stackoverflow.com/a/34749879/7657675
        #
        # See also the MS documentation about thumbprint
        # https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509certificate2.thumbprint?view=net-6.0#system-security-cryptography-x509certificates-x509certificate2-thumbprint

        # First run the openssl CLI to connect to the server. This logs the peer
        # certificate, and more besides.
        s_clientRun = subprocess.run(
            (
                'openssl', 's_client', '-servername', serverName, '-showcerts'
                , '-CAfile', str(self._pemPath), '-connect', connectAddress
            ), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE
            , stderr=subprocess.PIPE, text=True
        )
        self._log(httpHandler, f'openssl s_client stderr\n{s_clientRun.stderr}')

        # Extract the PEM dump of the peer certificate from the s_client output.
        s_clientCertificatePEM = None
        for line in s_clientRun.stdout.splitlines(True):
            if line.startswith('--') and 'BEGIN CERTIFICATE' in line:
                s_clientCertificatePEM = []
            if s_clientCertificatePEM is not None:
                s_clientCertificatePEM.append(line)
            if line.startswith('--') and 'END CERTIFICATE' in line:
                break
        self._log(httpHandler
            , f'openssl s_client PEM lines: {len(s_clientCertificatePEM)}')

        # Pipe the PEM back into the openssl x509 CLI and have it calculate the
        # thumbprint aka fingerprint.
        x509Run = subprocess.run(
            ('openssl', 'x509', '-inform', 'PEM', '-fingerprint', '-noout')
            , input=''.join(s_clientCertificatePEM)
            , stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        self._log(httpHandler, f'openssl x509\n{x509Run.stdout}')

    def _log(self, httpHandler, message):
        if httpHandler is None:
            print(message)
        else:
            httpHandler.log_message("%s", message)
    
class FetchCommandHandler(CommandHandler):
    def __init__(self):
        self._fetcher = Fetcher()
        super().__init__()

    # Override.
    def __call__(self, commandObject, httpHandler):
        command, parameters = self.parseCommandObject(commandObject)

        if command != 'fetch':
            return None

        return self._fetcher.fetch(parameters, httpHandler)
