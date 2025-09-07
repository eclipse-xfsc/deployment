import { Button } from 'react-bootstrap';
import css from './Header.module.scss';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faUser } from '@fortawesome/free-solid-svg-icons';

interface ISearchUserLoginState {
  text: string;
  onClick: () => void;
}

const SearchUserLoginState = ({ text, onClick }: ISearchUserLoginState): JSX.Element => {
  return (
    <div className={css['account-icon-wrapper']}>
      <Button
        variant="outline-light"
        className="border-0"
        data-state={text}
      >
        <FontAwesomeIcon
          icon={faUser}
          className={css['account-icon']}
        />
        <span
          className={`${css.pointer}`}
          onClick={onClick}
        >
          {text}
        </span>
      </Button>
    </div>
  );
};

export default SearchUserLoginState;
