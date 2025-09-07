import type { CodedVerifiableCredentials } from '@/service/types';

export function GET(req: Request, res: Response): Response {
  return new Response(
    JSON.stringify([
      {
        description: {
          id: '',
          format: '',
        },
        credentials: {
          '573281dd-4a29-4825-8e2f-3f7aabd80ed3': {
            data: 'eyJ0eXAiOiJzZC1qd3QiLCJhbGciOiJFZERTQSIsImtpZCI6Imh0dHBzOi8vY2xvdWQtd2FsbGV0Lnhmc2MuZGV2IzAifQ.eyJmYW1pbHlfbmFtZSI6InRlc3QiLCJnaXZlbl9uYW1lIjoidGVzdCIsImNuZiI6eyJqd2siOnsiYWxnIjoiRWREU0EiLCJjcnYiOiJFZDI1NTE5Iiwia2lkIjoiY2RjZDgwZjMtOGU3MS00ZDdmLWIxMTEtOGI0M2NiNWIxNjcyIiwia3R5IjoiT0tQIiwieCI6Imprdl9kU3pSUlU0aDBGbHBfWllOWTZQN2N2NlNWcWNLTzdSWFFScVByOXcifX0sImlzcyI6Imh0dHBzOi8vY2xvdWQtd2FsbGV0Lnhmc2MuZGV2IiwiaWF0IjoxNzI5MjYxNzk4LCJ2Y3QiOiJTREpXVENyZWRlbnRpYWwiLCJfc2RfYWxnIjoiU0hBLTI1NiJ9.vx9U3wb301LXYeDFgktWeRxgeVqDr8ME7WlJknF196E4YNTRviDOeppMnGDHhwR4X3zfg9H6OFHX5SikYbAXBw~',
            type: 'vc+sd-jwt',
          },
          'be0d6ee8-7e94-4a12-88c7-244f28450bd3': {
            data: 'eyJ0eXAiOiJzZC1qd3QiLCJhbGciOiJFZERTQSIsImtpZCI6Imh0dHBzOi8vY2xvdWQtd2FsbGV0Lnhmc2MuZGV2IzAifQ.eyJmYW1pbHlfbmFtZSI6InRlc3QiLCJnaXZlbl9uYW1lIjoidGVzdCIsInBpbl9vdHAiOnRydWUsImNuZiI6eyJqd2siOnsiYWxnIjoiRWREU0EiLCJjcnYiOiJFZDI1NTE5Iiwia2lkIjoiY2RjZDgwZjMtOGU3MS00ZDdmLWIxMTEtOGI0M2NiNWIxNjcyIiwia3R5IjoiT0tQIiwieCI6Imprdl9kU3pSUlU0aDBGbHBfWllOWTZQN2N2NlNWcWNLTzdSWFFScVByOXcifX0sImlzcyI6Imh0dHBzOi8vY2xvdWQtd2FsbGV0Lnhmc2MuZGV2IiwiaWF0IjoxNzI5MjYyNTkzLCJ2Y3QiOiJTREpXVENyZWRlbnRpYWwiLCJfc2RfYWxnIjoiU0hBLTI1NiJ9.mhXpGKiYTuPRS2Ag5PcVWKJQl6HbA1VVyYY4oFC5bsBDmXM3OfVlsvkJO21ykdliAJbHtGeuCU-PW9UCzMEpBA~',
            type: 'vc+sd-jwt',
          },
          'fadde8d9-81bb-4c79-a101-314f3049f3a5': {
            data: 'eyJ0eXAiOiJzZC1qd3QiLCJhbGciOiJFZERTQSIsImtpZCI6Imh0dHBzOi8vY2xvdWQtd2FsbGV0Lnhmc2MuZGV2IzAifQ.eyJmYW1pbHlfbmFtZSI6InRlc3QiLCJnaXZlbl9uYW1lIjoidGVzdCIsImNuZiI6eyJqd2siOnsiYWxnIjoiRWREU0EiLCJjcnYiOiJFZDI1NTE5Iiwia2lkIjoiY2RjZDgwZjMtOGU3MS00ZDdmLWIxMTEtOGI0M2NiNWIxNjcyIiwia3R5IjoiT0tQIiwieCI6Imprdl9kU3pSUlU0aDBGbHBfWllOWTZQN2N2NlNWcWNLTzdSWFFScVByOXcifX0sImlzcyI6Imh0dHBzOi8vY2xvdWQtd2FsbGV0Lnhmc2MuZGV2IiwiaWF0IjoxNzI5MjYxNTk0LCJ2Y3QiOiJTREpXVENyZWRlbnRpYWwiLCJfc2RfYWxnIjoiU0hBLTI1NiJ9.2MXljluuRZMqW7AIwGwtsneqYbGWGCq8qhrKUG-CPYvKKzkX8FC_REN1Lohz733MgE2H7EexB1niW0bHFxbrAw~',
            type: 'vc+sd-jwt',
          },
          'ffa3af50-1292-4395-a2e3-c430a3676243': {
            data: '{"@context":["https://www.w3.org/2018/credentials/v1","https://schema.org","https://w3id.org/security/suites/jws-2020/v1"],"credentialSubject":{"family_name":"test","given_name":"test","id":"did:jwk:eyJhbGciOiJFZERTQSIsImNydiI6IkVkMjU1MTkiLCJraWQiOiJjZGNkODBmMy04ZTcxLTRkN2YtYjExMS04YjQzY2I1YjE2NzIiLCJrdHkiOiJPS1AiLCJ4Ijoiamt2X2RTelJSVTRoMEZscF9aWU5ZNlA3Y3Y2U1ZxY0tPN1JYUVJxUHI5dyJ9"},"issuanceDate":"2024-10-21T13:00:20.308849978Z","issuer":"https://cloud-wallet.xfsc.dev","proof":{"challenge":"ffa3af50-1292-4395-a2e3-c430a3676243","created":"2024-10-21T13:00:20.315014932Z","jws":"eyJhbGciOiJFZERTQSIsImI2NCI6ZmFsc2UsImNyaXQiOlsiYjY0Il19..9TgtzcDJaJia1f-FcXDuxuQAMVKDDROXb6WBy6dCWMs32wPCZMBJxa4kbYaM40WzFTwwuL8peT-KC0b-S_1sCg","proofPurpose":"assertionMethod","type":"JsonWebSignature2020","verificationMethod":"https://cloud-wallet.xfsc.dev#signerkey"},"type":["VerifiableCredential","DeveloperCredential"]}',
            type: 'ldp_vc',
          },
        },
      },
    ] satisfies CodedVerifiableCredentials[]),
    {
      headers: {
        'content-type': 'application/json;charset=UTF-8',
      },
    }
  );
}
