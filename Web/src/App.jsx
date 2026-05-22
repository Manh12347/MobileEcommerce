import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { LoginForm } from './components/login-form'
import { DashboardLayout } from './components/dashboard/DashboardLayout'
import { DashboardPage } from './pages/dashboard/DashboardPage'
import { DiscountsPage } from './pages/dashboard/DiscountsPage'
import { BrandsPage } from './pages/dashboard/BrandsPage'
import { CategoriesPage } from './pages/dashboard/CategoriesPage'
import { ProductsPage } from './pages/dashboard/ProductsPage'
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
        <Route
          path="/dashboard/brands"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <BrandsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/dashboard/categories"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <CategoriesPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/dashboard/products"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <ProductsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

export default App
