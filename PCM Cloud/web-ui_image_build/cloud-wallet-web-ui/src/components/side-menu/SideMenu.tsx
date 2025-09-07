'use client';

import { useState } from 'react';
import MenuButton from './MenuButton';
import { Offcanvas, OffcanvasBody } from 'react-bootstrap';
import css from './SideMenu.module.scss';
import SideMenuItem from './SideMenuItem';
import { type MenuItem, getMenuItems } from '@/utils/headerData';
import { useRouter } from 'next/navigation';
import { useLocale, useTranslations } from 'next-intl';

interface SubMenuData {
  items: MenuItem[];
  title: string;
  id: string;
  path?: string | undefined;
}

const SideMenu = (): JSX.Element => {
  const [show, setShow] = useState(false);
  const [subItem, setSubItem] = useState<MenuItem>();
  const router = useRouter();
  const locale = useLocale();
  const t = useTranslations('IndexHeader');

  const handleMenuBtnClick = (): void => {
    setShow(state => (state = !state));
  };

  const handleMenuItemClick = (item: MenuItem): void => {
    if (item.items && item.items.length > 0) {
      setSubItem(item);
      return;
    }

    if (subItem && item.id === subItem.id) {
      setSubItem(undefined);
      return;
    }

    if (item.path && !item.path.startsWith('#')) {
      router.push(item.path);
      setShow(false);
    }
  };

  const getMenuData = (data: MenuItem[]): MenuItem[] => {
    return [...data];
  };

  const getSubMenuData = (data: MenuItem): SubMenuData => {
    return {
      ...data,
      items: [
        {
          ...data,
          items: undefined,
        },
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        ...data.items!,
      ],
    };
  };

  const handleExited = (): void => {
    setSubItem(undefined);
  };

  const handleHide = (): void => {
    setShow(false);
  };

  return (
    <>
      <MenuButton
        open={show}
        onClick={handleMenuBtnClick}
      />
      <Offcanvas
        responsive="md"
        show={show}
        onHide={handleHide}
        onExited={handleExited}
        className={css['side-menu']}
      >
        <OffcanvasBody className={css['side-menu-body']}>
          {!subItem &&
            getMenuData(getMenuItems(t, locale)).map(item => {
              return (
                <SideMenuItem
                  key={item.id}
                  menuItem={item}
                  onClick={() => handleMenuItemClick(item)}
                />
              );
            })}
          {subItem?.items &&
            getSubMenuData(subItem).items.map(item => {
              return (
                <SideMenuItem
                  key={item.id}
                  menuItem={item}
                  isBack={subItem.id === item.id}
                  onClick={() => handleMenuItemClick(item)}
                />
              );
            })}
        </OffcanvasBody>
      </Offcanvas>
    </>
  );
};

export default SideMenu;
