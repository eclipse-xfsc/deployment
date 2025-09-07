import css from './Line.module.scss';

interface LineProps {
  className?: string;
}

const Line = (props: LineProps): JSX.Element => {
  const classNames = `${props.className ?? ''} ${css.line} line`;

  return <div className={classNames} />;
};

export default Line;
