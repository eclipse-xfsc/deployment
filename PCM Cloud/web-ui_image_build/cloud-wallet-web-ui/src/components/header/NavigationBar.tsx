import { getMenuItems } from '@/utils/headerData';
import GxfsNavDropdown from './GxfsNavDropdown';
import css from './Header.module.scss';
import { useLocale, useTranslations } from 'next-intl';

const NavigationBar = (): JSX.Element => {
  const t = useTranslations('IndexHeader');
  const locale = useLocale();

  return (
    <div className={`${css['flex-center']} gap-2 d-none d-md-flex ${css.navigation}`}>
      {getMenuItems(t, locale).map(item => {
        return (
          <div key={item.id}>
            <GxfsNavDropdown menuItem={item}></GxfsNavDropdown>
          </div>
        );
      })}
    </div>
  );
};

export default NavigationBar;
