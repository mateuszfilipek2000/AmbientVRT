import type { Meta, StoryObj } from '@storybook/react-native-web-vite';

import { Button } from './components/Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  args: {
    label: 'Get started',
  },
};

export default meta;

type Story = StoryObj<typeof Button>;

export const Primary: Story = {
  args: { variant: 'primary' },
};

export const Secondary: Story = {
  args: { variant: 'secondary', label: 'Learn more' },
};

export const Disabled: Story = {
  args: { variant: 'primary', label: 'Unavailable', disabled: true },
};
