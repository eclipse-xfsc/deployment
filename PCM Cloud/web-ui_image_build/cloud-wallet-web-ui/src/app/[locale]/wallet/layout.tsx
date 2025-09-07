import '../../../scss/globals.scss';
import 'react-toastify/dist/ReactToastify.css';
import css from './layout.module.scss';
import WalletHeader from '@/components/header/WalletHeader';
import WalletSideMenu from '@/components/side-menu/WalletSideMenu';

import { WalletProvider } from '@/store/Provider';
import { type Metadata } from 'next';
import { NextIntlClientProvider, useMessages } from 'next-intl';

export const metadata: Metadata = {
  title: 'Wallet',
  icons: ['/images/favicon.ico'],
};

const WalletLayout = ({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}): JSX.Element => {
  const messages = useMessages();

  return (
    <html lang={locale}>
      <body className={css.wrapper}>
        <WalletProvider>
          <NextIntlClientProvider
            locale={locale}
            messages={messages}
          >
            <WalletSideMenu />
            <div className={`${css['content-wrapper']}`}>
              <div className={css.content}>
                <WalletHeader />
                {children}
              </div>
            </div>
          </NextIntlClientProvider>
        </WalletProvider>
      </body>
    </html>
  );
};

export default WalletLayout;
