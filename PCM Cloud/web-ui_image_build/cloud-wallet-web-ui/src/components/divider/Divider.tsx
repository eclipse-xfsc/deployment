import css from './Divider.module.scss';

interface DividerProps {
  className?: string;
  type?: 'vertical' | 'horizontal';
}

const Divider = ({ className, type }: DividerProps): JSX.Element => {
  return <div className={`${css.divider} ${className} ${type === 'vertical' ? css.vertical : css.horizontal}`} />;
};

export default Divider;
