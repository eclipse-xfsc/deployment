import { Container, Image } from 'react-bootstrap';
import { NoPaddingFlexColumnContainer } from '../container/Container';
import css from './SideMenu.module.scss';
import { type MenuItem } from '@/utils/headerData';

interface SideMenuItemProps {
  menuItem: MenuItem;
  onClick: () => void;
  isBack?: boolean;
}

const SideMenuItem = ({ menuItem, onClick, isBack }: SideMenuItemProps): JSX.Element => {
  const isActive = false;

  return (
    <NoPaddingFlexColumnContainer
      className={css['item-container']}
      onClick={onClick}
    >
      <Container className={!isBack ? css['space-between'] : ''}>
        {/* indicator icon for menu level up */}
        {isBack && (
          <Image
            alt="nav-icon"
            className={`${css.arrow} ${css.left} `}
          />
        )}

        <h2 className={isActive ? css.active : ''}>
          <>{menuItem.title}</>
        </h2>

        {/* indicator icon for menu level down */}
        {menuItem.items && menuItem.items.length > 0 && (
          <Image
            alt="nav-icon"
            className={`${css.arrow} ${css.right}`}
          />
        )}
      </Container>
    </NoPaddingFlexColumnContainer>
  );
};

export default SideMenuItem;
