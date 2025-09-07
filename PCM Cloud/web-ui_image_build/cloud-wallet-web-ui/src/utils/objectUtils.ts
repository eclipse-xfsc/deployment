import type { CredentialSubjectOffering, DetailedDisplay } from '../service/types';

export function getDisplayName(credentialSubject: CredentialSubjectOffering, key: string, locale: string): string {
  const display = credentialSubject[key].display;

  if (!display) return key;

  if (!Array.isArray(display)) return key;

  const name = display.find(item => {
    if (!item.locale) return false;

    return item.locale === locale || item.locale.split('-')[0] === locale;
  });

  return name ? name.name : display[0].name;
}

export function getDetailedDisplay(display: DetailedDisplay[], locale: string): DetailedDisplay {
  locale = locale.split('-')[0];

  const detailedDisplay = display.find(item => item.locale === locale);

  return detailedDisplay ?? display[0];
}
