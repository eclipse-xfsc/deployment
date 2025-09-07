import { Container, Image } from 'react-bootstrap';
import SideMenu from '../side-menu/SideMenu';
import AccountButton from './AccountButton';
import css from './Header.module.scss';
import NavigationBar from './NavigationBar';
import Link from 'next/link';

const Header = (): JSX.Element => {
  return (
    <>
      {
        <Container
          className={css.header}
          fluid
        >
          <div className={`${css['logo-wrapper']}`}>
            <Link href="/">
              <Image
                className={`${css['gaia-logo']}`}
                src="/xfsc1.png"
                alt="Logo"
              />
            </Link>
          </div>
          <SideMenu />
          <div className="d-flex justify-content-end align-content-center justify-content-md-between w-100">
            <NavigationBar />
            <AccountButton />
          </div>
        </Container>
      }
    </>
  );
};

export default Header;
