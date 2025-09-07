import { useTranslations } from 'next-intl';
import css from './WelcomeText.module.scss';

const WelcomeText = (): JSX.Element => {
  const t = useTranslations('IndexBanner');

  return (
    <div className={`${css.wrapper}`}>
      <div className={css.text}>
        <h1>{t('title')}</h1>
        <p>{t('subtitle')}</p>
      </div>
    </div>
  );
};

export default WelcomeText;
