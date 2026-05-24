import axios from 'axios';

// Detect environment and set base URL
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/v1/api';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired or unauthorized
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Auth endpoints
export const authAPI = {
  register: (email, password) =>
    apiClient.post('/auth/register', { email, password }),
  
  verifyOtp: (email, otp) =>
    apiClient.post('/auth/verify-otp', { email, otp }),
  
  login: (email, password) =>
    apiClient.post('/auth/login', { email, password }),
  
  logout: () =>
    apiClient.post('/auth/logout'),
  
  refreshToken: (refreshToken) =>
    apiClient.post('/auth/refresh-token', { refreshToken }),
};

export const warrantyAPI = {
  getClaimGroups: (params = {}) =>
    apiClient.get('/warranty-claims/grouped', { params }),

  getClaims: (params = {}) =>
    apiClient.get('/warranty-claims', { params }),

  updateClaimStatus: (claimId, status) =>
    apiClient.put(`/warranty-claims/${claimId}`, { status }),
};

export const catalogAPI = {
  getBrands: () => apiClient.get('/catalogs/brands'),
  createBrand: (payload) => apiClient.post('/catalogs/brands', payload),
  updateBrand: (id, payload) => apiClient.put(`/catalogs/brands/${id}`, payload),
  toggleBrandStatus: (id) => apiClient.put(`/catalogs/brands/${id}/toggle-status`),
  deleteBrand: (id) => apiClient.delete(`/catalogs/brands/${id}`),

  getCategories: () => apiClient.get('/catalogs/categories'),
  createCategory: (payload) => apiClient.post('/catalogs/categories', payload),
  updateCategory: (id, payload) => apiClient.put(`/catalogs/categories/${id}`, payload),
  toggleCategoryStatus: (id) => apiClient.put(`/catalogs/categories/${id}/toggle-status`),
  deleteCategory: (id) => apiClient.delete(`/catalogs/categories/${id}`),

  getProducts: (params = {}) => apiClient.get('/catalogs/products', { params }),
  getAllProducts: () => apiClient.get('/catalogs/products/all'),
  createProduct: (payload) => apiClient.post('/catalogs/products', payload),
  updateProduct: (id, payload) => apiClient.put(`/catalogs/products/${id}`, payload),
  toggleProductStatus: (id) => apiClient.put(`/catalogs/products/${id}/toggle-status`),
  deleteProduct: (id) => apiClient.delete(`/catalogs/products/${id}`),
};

export const productItemAPI = {
  getAll: (params = {}) => apiClient.get('/product-items/list', { params }),
  getAllFull: (params = {}) => apiClient.get('/product-items', { params }),
  getByProduct: (productId) => apiClient.get(`/product-items/product/${productId}`),
  create: (payload) => apiClient.post('/product-items', payload),
  update: (id, payload) => apiClient.put(`/product-items/${id}`, payload),
  toggleStatus: (id) => apiClient.put(`/product-items/${id}/toggle-status`),
  delete: (id) => apiClient.delete(`/product-items/${id}`),
  addStock: (id, quantity) => apiClient.post(`/product-items/${id}/add-stock`, null, { params: { quantity } }),
  reduceStock: (id, quantity) => apiClient.post(`/product-items/${id}/reduce-stock`, null, { params: { quantity } }),
};

export default apiClient;
