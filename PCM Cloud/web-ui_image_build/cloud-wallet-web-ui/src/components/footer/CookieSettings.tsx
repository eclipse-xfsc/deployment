import { Button, Image, Stack } from 'react-bootstrap';
import css from './Footer.module.scss';
import CookieInfoSection from './CookieInfoSection';
import { useTranslations } from 'next-intl';

interface CookieSettingsProps {
  close: () => void;
}

export interface CookieInfo {
  name: string;
  provider: string;
  purpose: string;
  cookieName: string;
  expiry: string;
}

const CookieSettings = ({ close }: CookieSettingsProps): JSX.Element => {
  const t = useTranslations('CookieSettings');

  const ESSENTIAL_COOKIE: CookieInfo = {
    name: t('info-name'),
    provider: t('info-provider'),
    purpose: t('info-purpose'),
    cookieName: t('info-cookie-name'),
    expiry: t('info-expiry'),
  };

  return (
    <Stack
      direction="vertical"
      className="mt-2 ml-2 mr-2"
      gap={2}
    >
      <div>
        <Stack direction="horizontal">
          <Image
            className={css['gaia-logo']}
            src="/GXFS_logo_alone_White.png"
            alt="GXFS Logo"
          />
          <div className={css['gxfs-font-white-xxl-bold']}>{t('privacy-reference')}</div>
        </Stack>
      </div>
      <div className={css['gxfs-font-white-xxxs-normal']}>{t('description')}</div>
      <div>
        <Button
          variant="dark"
          onClick={close}
        >
          {t('button')}
        </Button>
      </div>
      <div>
        <CookieInfoSection
          cookieType={t('essencial')}
          descripton={t('essencial-description')}
          info={ESSENTIAL_COOKIE}
        ></CookieInfoSection>
      </div>
    </Stack>
  );
};

export default CookieSettings;
