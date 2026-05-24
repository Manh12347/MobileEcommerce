import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { LoginForm } from './components/login-form'
import { DashboardLayout } from './components/dashboard/DashboardLayout'
import { DashboardPage } from './pages/dashboard/DashboardPage'
import { DiscountsPage } from './pages/dashboard/DiscountsPage'
import { BrandsPage } from './pages/dashboard/BrandsPage'
import { CategoriesPage } from './pages/dashboard/CategoriesPage'
import { OrdersPage } from './pages/dashboard/OrdersPage'
import { WarrantyPage } from './pages/dashboard/WarrantyPage'
import { ProductsPage } from './pages/dashboard/ProductsPage'
import { VariantsPage } from './pages/dashboard/VariantsPage'
import { UsersPage } from './pages/dashboard/UsersPage'
import { Toaster } from './components/ui/toast'
import { isAdminSessionActive } from './api/authSession'
import './index.css'

function ProtectedRoute({ children }) {
  if (!isAdminSessionActive()) {
    return <Navigate to="/" replace />
  }

  return children
}

function App() {
  return (
    <BrowserRouter>
      <Toaster />
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
          path="/dashboard/orders"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <OrdersPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/dashboard/warranty"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <WarrantyPage />
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
        <Route
          path="/dashboard/variants"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <VariantsPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/dashboard/users"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <UsersPage />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

export default App
