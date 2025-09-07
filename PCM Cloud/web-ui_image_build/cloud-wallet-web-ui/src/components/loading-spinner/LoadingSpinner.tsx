import { Spinner } from 'react-bootstrap';

const LoadingSpinner = (): JSX.Element => {
  return (
    <div className="vw-100 vh-100 d-flex justify-content-center align-items-center">
      <Spinner
        animation="border"
        variant="primary"
      />
    </div>
  );
};

export default LoadingSpinner;
