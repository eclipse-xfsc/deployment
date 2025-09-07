'use client';

import { faSearch } from '@fortawesome/free-solid-svg-icons';
import css from './SearchButton.module.scss';
import { Button, FormControl } from 'react-bootstrap';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { useEffect, useRef, useState } from 'react';
import { useTranslations } from 'next-intl';

interface SearchButtonProps {
  onSearch: (searchValue: string) => void;
}

const SearchButton = ({ onSearch }: SearchButtonProps): JSX.Element => {
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [searchValue, setSearchValue] = useState('');
  const searchRef = useRef<HTMLInputElement>(null);
  const t = useTranslations('CredentialsOverview');

  useEffect(() => {
    onSearch(searchValue);
  }, [searchValue]);

  useEffect(() => {
    if (isSearchOpen) {
      searchRef.current?.focus();

      document.addEventListener('click', handleClickOutside);
    }

    return () => {
      document.removeEventListener('click', handleClickOutside);
    };
  }, [isSearchOpen]);

  const handleClickOutside = (event: MouseEvent): void => {
    if (searchRef.current && !searchRef.current.contains(event.target as Node)) {
      setIsSearchOpen(false);
    }
  };

  return (
    <Button
      variant="light"
      className={`${css['flex-center']} gap-1 ${css['btn-search']}`}
      onClick={() => setIsSearchOpen(true)}
    >
      <FontAwesomeIcon
        icon={faSearch}
        width={20}
        height={20}
      />
      {isSearchOpen ? (
        <FormControl
          type="search"
          placeholder={t('search')}
          ref={searchRef}
          value={searchValue}
          onChange={e => setSearchValue(e.target.value)}
          className={`${css['search-input']} rounded-pill`}
        />
      ) : (
        t('search')
      )}
    </Button>
  );
};

export default SearchButton;
