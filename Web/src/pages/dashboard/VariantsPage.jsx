import { useState } from "react"
import { ProductVariantsTab } from "../../components/dashboard/ProductVariantsTab"

const mockProducts = [
  {
    id: 1, name: "iPhone 15 Pro Max", sku: "IPH15PM", image: "📱", brand: "Apple", category: "Smartphone", status: "active",
    variants: [
      { id: 101, variant: "256GB", price: 32990000, originalPrice: 34990000, stock: 25, sold: 120, rating: 4.8 },
      { id: 102, variant: "512GB", price: 36990000, originalPrice: 38990000, stock: 15, sold: 80, rating: 4.8 },
      { id: 103, variant: "1TB", price: 42990000, originalPrice: 44990000, stock: 5, sold: 34, rating: 4.9 },
    ]
  },
  {
    id: 2, name: "Samsung Galaxy S24 Ultra", sku: "SG24U", image: "📱", brand: "Samsung", category: "Smartphone", status: "active",
    variants: [
      { id: 201, variant: "256GB", price: 28990000, originalPrice: 30990000, stock: 20, sold: 95, rating: 4.7 },
      { id: 202, variant: "512GB", price: 31990000, originalPrice: 33990000, stock: 12, sold: 60, rating: 4.7 },
      { id: 203, variant: "1TB", price: 36990000, originalPrice: 38990000, stock: 6, sold: 34, rating: 4.8 },
    ]
  },
  {
    id: 3, name: "Xiaomi Redmi Note 13 Pro", sku: "XMN13P", image: "📱", brand: "Xiaomi", category: "Smartphone", status: "active",
    variants: [
      { id: 301, variant: "128GB", price: 8990000, originalPrice: 9990000, stock: 60, sold: 300, rating: 4.5 },
      { id: 302, variant: "256GB", price: 10990000, originalPrice: 11990000, stock: 60, sold: 267, rating: 4.5 },
    ]
  },
  {
    id: 4, name: "OPPO Find X7 Pro", sku: "OPFX7P", image: "📱", brand: "OPPO", category: "Smartphone", status: "inactive",
    variants: [
      { id: 401, variant: "256GB", price: 19990000, originalPrice: 21990000, stock: 0, sold: 45, rating: 4.6 },
      { id: 402, variant: "512GB", price: 22990000, originalPrice: 24990000, stock: 0, sold: 44, rating: 4.6 },
    ]
  },
  {
    id: 5, name: "iPad Pro M4 11 inch", sku: "IPDP11M4", image: "📲", brand: "Apple", category: "iPad", status: "active",
    variants: [
      { id: 501, variant: "256GB WiFi", price: 26990000, originalPrice: 27990000, stock: 15, sold: 80, rating: 4.9 },
      { id: 502, variant: "512GB WiFi", price: 30990000, originalPrice: 31990000, stock: 8, sold: 50, rating: 4.9 },
      { id: 503, variant: "256GB 5G", price: 31990000, originalPrice: 32990000, stock: 2, sold: 26, rating: 4.8 },
    ]
  },
  {
    id: 6, name: "AirPods Pro 2", sku: "APP2", image: "🎧", brand: "Apple", category: "Tai nghe", status: "active",
    variants: [
      { id: 601, variant: "USB-C", price: 5490000, originalPrice: 5990000, stock: 50, sold: 250, rating: 4.8 },
      { id: 602, variant: "MagSafe", price: 5790000, originalPrice: 6290000, stock: 39, sold: 182, rating: 4.7 },
    ]
  },
]

export function VariantsPage() {
  const [products, setProducts] = useState(mockProducts)

  return <ProductVariantsTab products={products} setProducts={setProducts} />
}
