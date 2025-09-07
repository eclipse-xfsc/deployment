'use client';

import { useEffect, useState } from 'react';
import CookieSettings from './CookieSettings';
import css from './Footer.module.scss';
import { Col, Image, Offcanvas, OffcanvasBody, Row } from 'react-bootstrap';
import { useTranslations } from 'next-intl';

const Footer = (): JSX.Element => {
  const [showCookieSettings, setShowCookieSettings] = useState(false);
  const t = useTranslations('Footer');

  useEffect(() => {
    if (localStorage.getItem('cookieSettings') !== 'true') {
      setShowCookieSettings(true);
    }
  }, []);

  const handleCookieSettings = (): void => {
    localStorage.setItem('cookieSettings', 'true');

    setShowCookieSettings(false);
  };

  return (
    <footer className={css['footer-container']}>
      <Row className={`${css['py-3']} ${css.contact}`}>
        <Col
          sm={12}
          md={4}
          className={`${css['self-center']}`}
        >
          <a
            href="https://www.eco.de/"
            target="_blank"
            rel="noreferrer"
          >
            <Image
              src="/eco_Logo_red-1-1024x819.png"
              alt="Eco Logo"
              width={150}
              height={120}
            />
          </a>
        </Col>

        <Col
          sm={12}
          md={4}
        >
          <p className={css['center-text']}>
            {t('eco')}
            <br></br>
            {t('light-street')}
            <br></br>
            {t('cologne')}
            <br></br>
            {t('germany')}
            <br></br> <br></br>
            {t('email')}:&nbsp;
            <a
              className={css['non-underlined-link']}
              href="mailto:info@gxfs.de"
            >
              info@gxfs.de
            </a>
            <br></br>
            {t('tel')}: +49 221 700048 0
          </p>
        </Col>

        <Col
          sm={12}
          md={4}
          className={css['self-center']}
        >
          <a
            href="https://www.bmwk.de/Navigation/DE/Home/home.html"
            target="_blank"
            rel="noreferrer"
          >
            <Image
              src="/Gefoerdert_Durch_768x784.png"
              alt="Gefoerdert Durch Logo"
              width={150}
              height={153}
            />
          </a>
        </Col>
      </Row>

      <div className={css.divider} />

      <Row className={`${css['justify-content-md-center']} ${css['py-3']}`}>
        <Col xs="auto">
          <a
            href="https://www.bmwi.de/Navigation/DE/Home/home.html"
            target="_blank"
            rel="noreferrer"
          >
            {t('imprint')}
          </a>
        </Col>

        <Col xs="auto">
          <a
            href="https://www.bmwi.de/Navigation/DE/Home/home.html"
            target="_blank"
            rel="noreferrer"
          >
            {t('privacy')}
          </a>
        </Col>

        <Col xs="auto">
          <div className={css['underlined-link']}>
            <a className={css['col-md-auto']}>{t('cookie')}</a>
          </div>
        </Col>
      </Row>

      <div className={css['bold-divider']} />

      <Row className={css['copyright-row']}>
        <p className={`${css['py-2']}`}>
          © 2023{' '}
          <a
            className={css['non-underlined-link']}
            href="https://www.gxfs.eu"
            title="GXFS.de"
          >
            GXFS.eu
          </a>
          {'. '}
          {t('rights')}.
        </p>
      </Row>
      <Offcanvas
        show={showCookieSettings}
        onHide={() => setShowCookieSettings(false)}
        className={css['cookie-settings-container']}
        placement="bottom"
      >
        <OffcanvasBody
          className={css['cookie-settings-offcanvas']}
          id="cookie-settings-offcanvas"
        >
          <CookieSettings close={handleCookieSettings}></CookieSettings>
        </OffcanvasBody>
      </Offcanvas>
    </footer>
  );
};

export default Footer;
