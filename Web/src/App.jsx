import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom"
import { DashboardLayout } from './components/dashboard/DashboardLayout'
import { LoginForm } from './components/login-form'
import {
  DashboardPage,
  UsersPage,
  DiscountsPage,
  BrandsPage,
  CategoriesPage,
  ProductsPage,
  OrdersPage,
  WarrantyPage,
} from './pages/dashboard'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Public Routes */}
        <Route path="/" element={<LoginForm />} />
        
        {/* Dashboard Routes */}
        <Route path="/dashboard" element={
          <DashboardLayout>
            <DashboardPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/users" element={
          <DashboardLayout>
            <UsersPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/discounts" element={
          <DashboardLayout>
            <DiscountsPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/brands" element={
          <DashboardLayout>
            <BrandsPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/categories" element={
          <DashboardLayout>
            <CategoriesPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/products" element={
          <DashboardLayout>
            <ProductsPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/orders" element={
          <DashboardLayout>
            <OrdersPage />
          </DashboardLayout>
        } />
        <Route path="/dashboard/warranty" element={
          <DashboardLayout>
            <WarrantyPage />
          </DashboardLayout>
        } />
        
        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
