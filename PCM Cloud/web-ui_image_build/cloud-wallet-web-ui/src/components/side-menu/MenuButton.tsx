import { Button, Collapse, Stack } from 'react-bootstrap';
import css from './SideMenu.module.scss';
import BurgerMenu from '../burger-menu/BurgerMenu';

interface MenuButtonProps {
  onClick: () => void;
  open: boolean;
}

const MenuButton = ({ open, onClick }: MenuButtonProps): JSX.Element => {
  return (
    <Button
      className={`${css['menu-btn']} ${css['small-and-xs-only']} ${css.btn} ${css['cancel-padding']}`}
      onClick={onClick}
    >
      <Stack
        className={css['small-and-xs-only']}
        direction="horizontal"
        gap={2}
      >
        <BurgerMenu open={open} />
        <Collapse
          dimension={'width'}
          appear
          in={!open}
        >
          <span className={css.dropdown}>Menu</span>
        </Collapse>
      </Stack>
    </Button>
  );
};

export default MenuButton;
