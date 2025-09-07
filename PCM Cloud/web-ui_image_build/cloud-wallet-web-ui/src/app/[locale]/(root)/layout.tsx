import type { Metadata } from 'next';
import '../../../scss/globals.scss';
import Header from '@/components/header/Header';
import Footer from '@/components/footer/Footer';
import { AppProvider } from '@/store/Provider';
import { NextIntlClientProvider, useMessages } from 'next-intl';

export const metadata: Metadata = {
  title: 'PCM Web',
  description: 'Personal Credential Manager Web Interface',
  icons: ['/images/favicon.ico'],
};

const RootLayout = ({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}): JSX.Element => {
  const messages = useMessages();

  return (
    <html lang={locale}>
      <body>
        <AppProvider>
          <NextIntlClientProvider
            locale={locale}
            messages={messages}
          >
            <div className="min-vh-100 d-flex flex-column">
              <Header />
              <div>{children}</div>
              <Footer />
            </div>
          </NextIntlClientProvider>
        </AppProvider>
      </body>
    </html>
  );
};

export default RootLayout;
