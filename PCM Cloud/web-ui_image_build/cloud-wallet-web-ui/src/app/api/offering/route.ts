import type { OfferingData } from '@/service/types';

export function GET(req: Request, res: Response): Response {
  return new Response(
    JSON.stringify([
      {
        groupId: 'group-123',
        requestId: 'request-456',
        metadata: {
          credential_issuer: 'Issuer Inc.',
          authorization_servers: ['auth-server-1', 'auth-server-2'],
          credential_endpoint: 'https://issuer.example.com/credential',
          signed_metadata: null,
          notification_endpoint: null,
          batch_credential_endpoint: null,
          deferred_credential_endpoint: null,
          credential_identifiers_supported: true,
          credential_response_encryption: {
            alg_values_supported: ['RS256', 'ES256'],
            enc_values_supported: ['A128CBC-HS256', 'A256GCM'],
            encryption_required: true,
          },
          display: null,
          credential_configurations_supported: {
            degree: {
              format: 'jwt',
              scope: 'openid profile email',
              cryptographic_binding_methods_supported: ['did:example:123#key-1'],
              credential_signing_alg_values_supported: ['ES256', 'RS256'],
              credential_definition: {
                type: ['VerifiableCredential', 'UniversityDegreeCredential'],
                credentialSubject: {
                  id: {
                    display: {
                      name: 'ID',
                      locale: 'en-US',
                    },
                  },
                  degree: {
                    display: [
                      {
                        name: 'Degree',
                        locale: 'en-US',
                      },
                      {
                        name: 'Título',
                        locale: 'es-ES',
                      },
                    ],
                  },
                },
              },
              proof_types_supported: {
                'proof-type-1': {
                  proof_signing_alg_values_supported: ['ES256K'],
                },
              },
              display: [
                {
                  name: 'Example Credential',
                  locale: 'en-US',
                  logo: {
                    url: 'https://issuer.example.com/logo.png',
                    alternative_text: 'Issuer Logo',
                  },
                  background_color: '#FFFFFF',
                  text_color: '#000000',
                },
              ],
            },
          },
        },
        offering: {
          credential_issuer: 'Issuer Inc.',
          credential_configuration_ids: ['degree', 'transcript'],
          grants: {
            authorization_code: {
              issuer_state: 'received',
            },
            'urn:ietf:params:oauth:grant-type:pre-authorized_code': {
              'pre-authorized_code': 'preauthcode-123',
              tx_code: {
                input_mode: 'numeric',
                length: 5,
                description: 'Type in your pin.',
              },
              interval: 5,
            },
          },
        },
        status: 'received',
        timestamp: '2024-06-03T10:00:00Z',
      },
    ] satisfies OfferingData[]),
    {
      headers: {
        'content-type': 'application/json;charset=UTF-8',
      },
    }
  );
}
