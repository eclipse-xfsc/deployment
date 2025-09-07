import css from './BurgerMenu.module.scss';

interface BurgerMenuProps {
  open: boolean;
}

const BurgerMenu = ({ open }: BurgerMenuProps): JSX.Element => {
  return (
    <div className={`${css['burger-menu']} ${open ? css.open : ''}`}>
      <span></span>
      <span></span>
      <span></span>
    </div>
  );
};

export default BurgerMenu;
