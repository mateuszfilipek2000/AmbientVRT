import type { Meta, StoryObj } from '@storybook/react-native-web-vite';

import { Card } from './components/Card';

// Card pulls copy from the active locale and colors from the active theme, so
// it is the story that best exercises both variant globals at once.
const meta: Meta<typeof Card> = {
  title: 'Components/Card',
  component: Card,
};

export default meta;

type Story = StoryObj<typeof Card>;

export const Default: Story = {};
