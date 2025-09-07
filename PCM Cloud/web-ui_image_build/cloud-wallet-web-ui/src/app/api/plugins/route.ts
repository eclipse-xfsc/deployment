interface Plugin {
  name: string;
  route: string;
  url: string;
}

interface PluginDiscoveryResponse {
  plugins: Plugin[];
}

export function GET(req: Request, res: Response): Response {
  return new Response(
    JSON.stringify({
      plugins: [
        {
          name: 'test',
          route: 'test',
          url: 'https://raw.githubusercontent.com/EduardoOrthmann/remote-component-starter/master/transpiled/main.js',
        },
      ],
    } satisfies PluginDiscoveryResponse),
    {
      headers: {
        'content-type': 'application/json;charset=UTF-8',
      },
    }
  );
}
