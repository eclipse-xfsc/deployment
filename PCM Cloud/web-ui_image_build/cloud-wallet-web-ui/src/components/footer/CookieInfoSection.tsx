'use client';

import { Stack } from 'react-bootstrap';
import { type CookieInfo } from './CookieSettings';
import css from './Footer.module.scss';
import { useState } from 'react';
import Link from 'next/link';
import { useTranslations } from 'next-intl';

interface CookieInfoSectionProps {
  cookieType: string;
  descripton: string;
  info: CookieInfo;
}

const CookieInfoSection = (props: CookieInfoSectionProps): JSX.Element => {
  const [showCookieInformation, setShowCookieInformation] = useState(false);
  const t = useTranslations('CookieSettings');

  const toogleShowCookieInformation = (): void => {
    setShowCookieInformation(!showCookieInformation);
  };

  const imprintLink = (
    <Link
      href="/imprint"
      className={css['cookie-info-toggle-text']}
    >
      {t('imprint')}
    </Link>
  );

  return (
    <div className={css['cookie-info-container']}>
      <Stack
        direction="vertical"
        className="ml-1 mr-1 mb-1"
        gap={2}
      >
        <div className={css['cookie-info-container']}>{props.cookieType} (1)</div>
        <div className={css['cookie-info-description']}>{props.descripton}</div>
        <div className="mb-1">
          <div
            className={css['cookie-info-toggle-text']}
            onClick={toogleShowCookieInformation}
          >
            <a className={css['cookie-info-toggle-text']}>
              {showCookieInformation ? t('hide-cookies') : t('show-cookies')}
            </a>
          </div>
        </div>
        {showCookieInformation && (
          <div className={css['cookie-info-description']}>
            <table className={css['cookie-info-table']}>
              <tbody>
                <tr>
                  <td>{t('name-label')}</td>
                  <td>{props.info.name}</td>
                </tr>
                <tr>
                  <td>{t('provider-label')}</td>
                  <td>
                    {props.info.provider} {imprintLink}
                  </td>
                </tr>
                <tr>
                  <td>{t('purpose-label')}</td>
                  <td>{props.info.purpose}</td>
                </tr>
                <tr>
                  <td>{t('cookie-name-label')}</td>
                  <td>{props.info.cookieName}</td>
                </tr>
                <tr>
                  <td>{t('expiry-label')}</td>
                  <td>{props.info.expiry}</td>
                </tr>
              </tbody>
            </table>
          </div>
        )}
      </Stack>
    </div>
  );
};

export default CookieInfoSection;
