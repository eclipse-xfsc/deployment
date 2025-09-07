import { Card, CardBody, CardText, CardTitle } from 'react-bootstrap';
import css from './Benefits.module.scss';

const benefits = [
  {
    title: 'Lorem 1',
    text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse malesuada lacus ex, sit amet blandit leo lobortis eget.',
  },
  {
    title: 'Lorem 2',
    text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse malesuada lacus ex, sit amet blandit leo lobortis eget.',
  },
  {
    title: 'Lorem 3',
    text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse malesuada lacus ex, sit amet blandit leo lobortis eget.',
  },
];

const Benefits = (): JSX.Element => {
  return (
    <div className={`${css.benefits} shadow`}>
      {benefits.map(benefit => (
        <Card
          key={benefit.title}
          className={css.card}
        >
          <CardBody>
            <CardTitle className={css.title}>{benefit.title}</CardTitle>
            <CardText>{benefit.text}</CardText>
          </CardBody>
        </Card>
      ))}
    </div>
  );
};

export default Benefits;
