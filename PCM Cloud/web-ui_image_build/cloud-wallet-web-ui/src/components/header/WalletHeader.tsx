import css from './WalletHeader.module.scss';
import { Nav, NavItem, Navbar, NavbarCollapse } from 'react-bootstrap';
import AccountButton from './AccountButton';

const WalletHeader = (): JSX.Element => {
  return (
    <Navbar
      className={`mb-4 shadow ${css.navbar}`}
      sticky="top"
    >
      <NavbarCollapse>
        <Nav className={css.nav}>
          <NavItem className={css['nav-action-item']}>
            <AccountButton />
          </NavItem>
        </Nav>
      </NavbarCollapse>
    </Navbar>
  );
};

export default WalletHeader;
