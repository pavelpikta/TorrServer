import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClientProvider, QueryClient } from 'react-query'

import App from './components/App'
import 'i18n'

const queryClient = new QueryClient()
const root = createRoot(document.getElementById('root'))

root.render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </StrictMode>,
)
