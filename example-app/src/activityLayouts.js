export function createDeliveryLayout() {
  return {
    layout: {
      type: 'container',
      direction: 'vertical',
      spacing: 8,
      children: [
        {
          type: 'container',
          direction: 'horizontal',
          spacing: 8,
          children: [
            {
              type: 'image',
              source: 'sfSymbol',
              value: 'box.truck.fill',
              width: 24,
              height: 24,
              tintColor: '#007AFF',
            },
            { type: 'text', content: 'Order #{{orderNumber}}', fontSize: 16, fontWeight: 'bold' },
          ],
        },
        { type: 'text', content: '{{status}}', fontSize: 14, color: '#666666' },
        { type: 'progress', value: 'progress', tint: '#34C759' },
      ],
    },
    dynamicIslandLayout: {
      expanded: {
        leading: { type: 'image', source: 'sfSymbol', value: 'box.truck.fill', tintColor: '#007AFF' },
        trailing: { type: 'text', content: '{{eta}}', fontWeight: 'semibold' },
        center: { type: 'text', content: '{{status}}', fontSize: 14 },
        bottom: { type: 'progress', value: 'progress', tint: '#34C759' },
      },
      compactLeading: { type: 'image', source: 'sfSymbol', value: 'box.truck.fill' },
      compactTrailing: { type: 'text', content: '{{eta}}' },
      minimal: { type: 'image', source: 'sfSymbol', value: 'box.truck.fill' },
    },
    behavior: {
      widgetUrl: 'capgoliveactivities://order/demo',
    },
  };
}

export const deliveryStages = [
  { status: 'Preparing your order', eta: '25 min', progress: 0.15 },
  { status: 'On the way', eta: '10 min', progress: 0.6 },
  { status: 'Arriving soon', eta: '2 min', progress: 0.9 },
  { status: 'Delivered', eta: 'Now', progress: 1 },
];
