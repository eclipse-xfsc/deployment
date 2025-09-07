import type { PresentationDefinitionData } from '@/service/types';

export function GET(req: Request, res: Response): Response {
  return new Response(
    JSON.stringify([
      {
        id: 'MEQCIF1hJfJ952mxgE76kH-wUKQWy5b7IH0u7IN3mvbBFSZgAiAiZC34YQPk5-AAxkwbgdh_LTlComgBi9-6L8elW_BSaw',
        name: 'test',
        purpose: 'I wanna see it!',
        input_descriptors: [
          {
            id: '5a9be371-2cf9-457e-9dbf-70212e5784fui',
            format: {},
            constraints: {
              fields: [
                {
                  path: ['$.credentialSubject[?(@ =~ /Fre/)]'],
                },
              ],
            },
          },
        ],
        format: {
          ldp_vc: {},
        },
      },
      {
        id: 'MEUCIQDQWNs639MH8ij97aZ_t6RKqkW_xIQ84T1gVypl8ifRSgIgJzAraoKXgM-hHQu54MbS7XRWWKn30I_8BmKKZ2nctMk',
        name: 'test',
        purpose: 'I wanna see it!',
        input_descriptors: [
          {
            id: '5a9be371-2cf9-457e-9dbf-70212e5784fii',
            format: {},
            constraints: {
              fields: [
                {
                  path: ['$.credentialSubject[?(@ =~ /Fre/)]'],
                },
              ],
            },
          },
        ],
        format: {
          ldp_vc: {},
        },
      },
    ] satisfies PresentationDefinitionData[]),
    {
      headers: {
        'content-type': 'application/json;charset=UTF-8',
      },
    }
  );
}
