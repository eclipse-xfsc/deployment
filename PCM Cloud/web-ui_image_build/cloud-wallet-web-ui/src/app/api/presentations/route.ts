import type { VerifiablePresentation } from '@/service/types';

export function POST(req: Request, res: Response): Response {
  return new Response(
    JSON.stringify([
      {
        description: {
          id: '7a9be371-2cf9-457e-9dbf-70212e5784fc',
          format: 'ldp_vc',
        },
        credentials: {
          '7a9be371-2cf9-457e-9dbf-70212e5784fc': {
            '@context': ['https://www.w3.org/2018/credentials/v1'],
            holder: 'did:example:holder',
            id: 'ebc6f1c2',
            proof: {
              challenge: 'n-0S6_WzA2Mj',
              created: '2021-03-19T15:30:15Z',
              domain: 'https://client.example.org/cb',
              jws: 'eyJhbG...IAoDA',
              proofPurpose: 'authentication',
              type: 'Ed25519Signature2018',
              verificationMethod: 'did:example:holder#key-1',
            },
            type: ['VerifiablePresentation'],
            verifiableCredential: [
              {
                '@context': [
                  'https://www.w3.org/2018/credentials/v1',
                  'https://www.w3.org/2018/credentials/examples/v1',
                ],
                credentialSubject: {
                  birthdate: '1949-01-22',
                  family_name: 'Strömberg',
                  given_name: 'Fredrik',
                },
                id: 'https://example.com/credentials/1872',
                issuanceDate: '2010-01-01T19:23:24Z',
                issuer: 'did:example:issuer',
                proof: {
                  created: '2021-03-19T15:30:15Z',
                  jws: 'eyJhb...JQdBw',
                  proofPurpose: 'assertionMethod',
                  type: 'Ed25519Signature2018',
                  verificationMethod: 'did:example:issuer#keys-1',
                },
                type: 'VerifiableCredential',
                vct: 'VerifiableCredential',
              },
            ],
          },
        },
      },
    ] satisfies VerifiablePresentation[]),
    {
      headers: {
        'content-type': 'application/json;charset=UTF-8',
      },
    }
  );
}
