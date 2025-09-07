import { type IconDefinition, faGear, faWallet } from '@fortawesome/free-solid-svg-icons';

export interface MenuItem {
  title: string;
  id: string;
  // subitems for dropdown
  items?: MenuItem[];
  // path to internal route or external website
  path: string;
}

export interface NavLink {
  name: string;
  icon: IconDefinition;
  children: LinkChild[];
  href?: string;
}

export interface LinkChild {
  name: string;
  href: string;
}

export function getMenuItems(t: (str: string) => string, locale: string): MenuItem[] {
  return [
    {
      title: t('federation'),
      id: 'federation',
      path: `/${locale}/wallet/credentials`,
      items: [
        {
          title: t('credentials'),
          id: 'credentials',
          path: `/${locale}/wallet/credentials`,
        },
        {
          title: t('selection'),
          id: 'selection',
          path: `/${locale}/wallet/selection`,
        },
        {
          title: t('issuance'),
          id: 'issuance',
          path: `/${locale}/wallet/issuance`,
        },
        {
          title: t('offering'),
          id: 'offering',
          path: `/${locale}/wallet/offering`,
        },
        {
          title: t('dids'),
          id: 'dids',
          path: `/${locale}/wallet/did`,
        },
      ],
    },
  ];
}

export function getWalletMenuItems(t: (str: string) => string, locale: string): NavLink[] {
  return [
    {
      name: t('credentials'),
      icon: faWallet,
      children: [
        {
          name: t('overview'),
          href: `/${locale}/wallet/credentials`,
        },
        {
          name: t('issuance'),
          href: `/${locale}/wallet/issuance`,
        },
        {
          name: t('presentation'),
          href: `/${locale}/wallet/selection`,
        },
        {
          name: t('presentations'),
          href: `/${locale}/wallet/presentations`,
        },
        {
          name: t('offering'),
          href: `/${locale}/wallet/offering`,
        },
      ],
    },
    {
      name: t('settings'),
      icon: faGear,
      href: `/${locale}/wallet/settings`,
      children: [
        {
          name: t('plugin-overview'),
          href: `/${locale}/wallet/plugin-overview`,
        },
        {
          name: t('pairing-management'),
          href: `/${locale}/wallet/pairing-management`,
        },
        {
          name: t('identity-overview'),
          href: `/${locale}/wallet/did`,
        },
        {
          name: t('backup'),
          href: `/${locale}/wallet/backup`,
        },
      ],
    },
  ];
}
