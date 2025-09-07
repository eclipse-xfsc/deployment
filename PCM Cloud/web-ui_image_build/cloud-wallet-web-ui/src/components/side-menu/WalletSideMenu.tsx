'use client';

import useScreenSize from '@/hooks/useScreenSize';
import { faBars, faChevronLeft, faHistory, faWallet } from '@fortawesome/free-solid-svg-icons';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Button, Image, Nav, NavbarBrand, NavItem } from 'react-bootstrap';
import css from './WalletSideMenu.module.scss';
import { useQueryClient } from '@tanstack/react-query';
import { type NavLink, getWalletMenuItems } from '@/utils/headerData';
import { useTranslations, useLocale } from 'next-intl';

export interface Plugin {
  name: string;
  route: string;
  url: string;
}

export interface PluginWrapper {
  plugins: Plugin[];
}

const WalletSideMenu = (): JSX.Element => {
  const [open, setOpen] = useState(false);
  const screenSize = useScreenSize();
  const pathname = usePathname();
  const t = useTranslations('WalletMenu');
  const locale = useLocale();
  const [links, setLinks] = useState(getWalletMenuItems(t, locale));
  const pluginDiscoveryData = useQueryClient().getQueryData<PluginWrapper>(['pluginDiscovery']);
  const sidebarRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!pluginDiscoveryData) return;

    const filteredLinks: NavLink[] = links.filter(link => link.name !== 'Plugins');

    const pluginParent: NavLink = {
      name: 'Plugins',
      icon: faWallet,
      children:
        pluginDiscoveryData?.plugins?.map((plugin: Plugin) => ({
          name: plugin.name,
          href: `/${locale}/wallet/plugins/${plugin.route}`,
        })) ?? [],
    };

    setLinks([...filteredLinks, pluginParent]);
  }, []);

  useEffect(() => {
    if (screenSize.width > 768 && open) {
      setOpen(false);
    }
  }, [screenSize.width, open]);

  useEffect(() => {
    if (open) {
      setOpen(false);
    }
  }, [pathname]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (sidebarRef.current && !sidebarRef.current.contains(event.target as Node) && open) {
        setOpen(false);
      }
    };

    if (screenSize.width < 768) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [open, screenSize.width]);

  const toggle = (): void => {
    setOpen(!open);
  };

  const isActiveLink = (href: string): boolean => {
    return pathname === href;
  };

  return (
    <>
      {/*  <!-- Hamburger Button --> */}
      <Button
        className={`${css['navbar-toggle']} text-dark border-0`}
        variant="outline-light"
        onClick={toggle}
      >
        <FontAwesomeIcon
          icon={faBars}
          className={css.icon}
        />
      </Button>

      <div
        className={`${css['sidebar-wrapper']} ${open ? css['wallet-sidebar-open'] : ''}`}
        ref={sidebarRef}
      >
        {/*  <!-- Sidebar --> */}
        <Nav className={`${css['wallet-sidebar']} flex-nowrap`}>
          <div>
            {/*  <!-- Sidebar - Brand --> */}
            <NavbarBrand className={`${css['wallet-navbar-brand']}`}>
              <Link href="/">
                <Image
                  className={css['gaia-logo']}
                  src="/xfsc1.png"
                  alt="Logo"
                />
              </Link>
            </NavbarBrand>

            <div className="p-1">
              {links.map((link: NavLink) => (
                <div
                  key={link.name}
                  className="p-2"
                >
                  <div className={`${css['nav-parent']} gap-2 mb-1 border-bottom pb-1`}>
                    <FontAwesomeIcon
                      icon={link.icon}
                      className={css.icon}
                    />
                    <strong>{link.href ? <Link href={link.href}>{link.name}</Link> : link.name}</strong>
                  </div>
                  <div>
                    {link.children.map(child => (
                      <NavItem
                        className={`${css['sidebar-item']} ${css['sidebar-child']}`}
                        key={child.name}
                      >
                        <Link
                          className={`${css['sidebar-link']} ${isActiveLink(child.href) ? css.active : ''}`}
                          href={child.href}
                        >
                          <span>{child.name}</span>
                        </Link>
                      </NavItem>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Collapse sidebar button */}
          <Button
            className={`${css['sidebar-collapse-button']} ${open ? css['wallet-sidebar-open'] : ''}`}
            onClick={toggle}
          >
            <FontAwesomeIcon
              icon={faChevronLeft}
              className={css.icon}
            />
          </Button>

          {/* Navbar Footer */}
          <div className={`${css['navbar-footer']} mb-2 mt-5`}>
            <NavItem className={`${css['sidebar-item']}`}>
              <Link
                className={`${css['sidebar-link']}`}
                href={`/${locale}/wallet/history`}
              >
                <FontAwesomeIcon
                  icon={faHistory}
                  className={css.icon}
                />
                <span>{t('history')}</span>
              </Link>
            </NavItem>
          </div>
        </Nav>
      </div>
    </>
  );
};

export default WalletSideMenu;
