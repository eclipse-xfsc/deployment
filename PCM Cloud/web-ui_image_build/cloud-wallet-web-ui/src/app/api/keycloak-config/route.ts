import type { KeycloakConfig } from '@/service/types';

export function GET(req: Request, res: Response): Response {
  return new Response(
    JSON.stringify({
      baseUrl: 'http://localhost:8081',
      auth: 'http://localhost:8081',
      realm: 'react-keycloak',
      clientId: 'react-keycloak',
    } satisfies KeycloakConfig),
    {
      headers: {
        'content-type': 'application/json;charset=UTF-8',
      },
    }
  );
}
