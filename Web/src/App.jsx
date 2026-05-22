import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { LoginForm } from './components/login-form'
import { DashboardLayout } from './components/dashboard/DashboardLayout'
import { DashboardPage } from './pages/dashboard/DashboardPage'
import { DiscountsPage } from './pages/dashboard/DiscountsPage'
import './index.css'

function ProtectedRoute({ children }) {
  const token = localStorage.getItem('accessToken')
  
  if (!token) {
    return <Navigate to="/" replace />
  }
  
  return children
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LoginForm />} />
        <Route
          path="/dashboard"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <DashboardPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/dashboard/discounts"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <DiscountsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

export default App
