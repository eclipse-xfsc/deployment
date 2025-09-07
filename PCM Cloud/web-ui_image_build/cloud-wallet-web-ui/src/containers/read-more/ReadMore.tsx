import Container from '@/components/container/Container';
import css from './ReadMore.module.scss';
import { Image } from 'react-bootstrap';
import { useTranslations } from 'next-intl';

interface ReadMoreProps {
  reversed?: boolean;
}

const ReadMore = ({ reversed }: ReadMoreProps): JSX.Element => {
  const t = useTranslations('ReadMore');

  return (
    <Container className={`${css.wrapper} ${reversed ? css.reversed : ''} py-0 mb-5`}>
      <Image
        src="/news_bg.png"
        alt="Read more"
        className={css['image-content']}
      />
      <div className={css['text-content']}>
        <h3 className={css['text-primary']}>{t('title')}</h3>
        <p>{t('description')}</p>
      </div>
    </Container>
  );
};

export default ReadMore;
