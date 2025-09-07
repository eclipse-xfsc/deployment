'use client';

import { type MenuItem } from '@/utils/headerData';
import { usePathname, useRouter } from 'next/navigation';
import { DropdownItem, NavDropdown } from 'react-bootstrap';
import css from './Header.module.scss';
import Link from 'next/link';

export interface GxfsNavDropdownProps {
  menuItem: MenuItem;
}

const GxfsNavDropdown = ({ menuItem }: GxfsNavDropdownProps): JSX.Element => {
  const router = useRouter();
  const pathname = usePathname();

  const handleNavigation = (path?: string): void => {
    if (path && !path.startsWith('#')) {
      void router.push(path);
    }
  };

  return (
    <>
      {menuItem.items != null ? (
        <NavDropdown
          title={menuItem.title}
          key={menuItem.id}
          id={menuItem.id}
          show
          renderMenuOnMount
        >
          {menuItem.items.map(item => {
            return (
              <DropdownItem
                active={item.path === pathname}
                as={Link}
                href={item.path}
                key={item.id}
              >
                {item.title}
              </DropdownItem>
            );
          })}
        </NavDropdown>
      ) : (
        <h2
          className={css.pointer}
          key={menuItem.id}
          onClick={() => handleNavigation(menuItem.path)}
        >
          {menuItem.title}
        </h2>
      )}
    </>
  );
};

export default GxfsNavDropdown;
