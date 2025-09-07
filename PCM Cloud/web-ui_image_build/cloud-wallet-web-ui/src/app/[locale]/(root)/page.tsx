import Container from '@/components/container/Container';
import WelcomeText from '@/containers/welcome-text/WelcomeText';
import css from './page.module.scss';
import ReadMore from '@/containers/read-more/ReadMore';
import { Button } from 'react-bootstrap';
import Benefits from '@/containers/benefits/Benefits';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faSignInAlt } from '@fortawesome/free-solid-svg-icons';
import { useTranslations } from 'next-intl';

const Home = (): JSX.Element => {
  const t = useTranslations('Auth');

  return (
    <div className={css.main}>
      <WelcomeText />
      <Container className={css['content-container']}>
        <ReadMore />
        <ReadMore reversed />

        <Button
          variant="primary"
          size="lg"
          className={`${css['login-button']} ${css['flex-center']} gap-2`}
        >
          <FontAwesomeIcon
            icon={faSignInAlt}
            width={20}
            height={20}
          />
          {t('to-the-login')}
        </Button>

        <Benefits />
      </Container>
    </div>
  );
};

export default Home;
