import { faFolder } from '@fortawesome/free-solid-svg-icons';
import css from './NoData.module.scss';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { useTranslations } from 'next-intl';

const NoData = (): JSX.Element => {
  const t = useTranslations('NoData');

  return (
    <div className={`${css['flex-center']} flex-column gap-2 ${css['no-data']}`}>
      <FontAwesomeIcon
        icon={faFolder}
        className={css.icon}
      />
      <h2>{t('no-data')}</h2>
    </div>
  );
};

export default NoData;
