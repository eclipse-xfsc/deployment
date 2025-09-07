'use client';

import { type PropsWithChildren } from 'react';
import { Fade, Container as BootstrapContainer, type ContainerProps as BootstrapContainerProps } from 'react-bootstrap';
import css from './Container.module.scss';
import Line from './line/Line';

interface ContainerProps {
  children: React.ReactNode;
  fluid?: boolean;
  className?: string;
}

const Container = ({ children, fluid = false, className = '' }: ContainerProps): JSX.Element => {
  return <div className={`${css.container} ${fluid ? css.fluid : ''} ${className}`}>{children}</div>;
};

export const FadeContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  return (
    <Fade
      in
      appear
    >
      <BootstrapContainer {...props}>{props.children}</BootstrapContainer>
    </Fade>
  );
};

export const FlexColumnContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = `${css['flex-column']} ${props.className ?? ''}`;

  return (
    <FadeContainer
      {...props}
      className={classNames}
    >
      {props.children}
    </FadeContainer>
  );
};

export const FlexRowContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = `${css['flex-row']}  ${props.className ?? ''}`;

  return (
    <FadeContainer
      {...props}
      className={classNames}
    >
      {props.children}
    </FadeContainer>
  );
};

export const NoPaddingFlexColumnContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = ` ${css['no-padding']} ${props.className ?? ''}`;

  return (
    <FlexColumnContainer
      {...props}
      className={classNames}
    >
      {props.children}
    </FlexColumnContainer>
  );
};

export const NoPaddingFlexRowContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = ` ${css['no-padding']} ${props.className ?? ''}`;

  return (
    <FlexRowContainer
      {...props}
      className={classNames}
    >
      {props.children}
    </FlexRowContainer>
  );
};

export const ContentContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = `${css.fill} ${css['pb-3rem']} ${props.className ?? ''}`;

  return (
    <MainContentContainer
      {...props}
      fluid
      className={classNames}
    >
      {props.children}
    </MainContentContainer>
  );
};

export const MainContentContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = `${css.fill} ${props.className ?? ''}`;

  return (
    <NoPaddingFlexColumnContainer
      {...props}
      fluid
      className={classNames}
    >
      {props.children}
    </NoPaddingFlexColumnContainer>
  );
};

export const LineContainer = (props: PropsWithChildren<BootstrapContainerProps>): JSX.Element => {
  const classNames = `${css.fill} ${props.className ?? ''}`;

  return (
    <NoPaddingFlexColumnContainer
      {...props}
      className={classNames}
    >
      <Line />
      {props.children}
    </NoPaddingFlexColumnContainer>
  );
};

export default Container;
