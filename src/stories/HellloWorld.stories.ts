import { fn } from '@storybook/test'
import type { Meta, StoryObj } from '@storybook/vue3'

import HelloWorld from '@/components/HelloWorld.vue'

const meta: Meta<typeof HelloWorld> = {
  title: 'Example/HelloWorld',
  component: HelloWorld,
  argTypes: {
    msg: { control: 'text' },
  },
} satisfies Meta<typeof HelloWorld>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    msg: 'Hello, World!',
  },
}
