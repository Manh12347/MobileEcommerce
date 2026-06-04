import axios from 'axios';
import { clearAdminSession, getAdminAccessToken } from './authSession';

// Detect environment and set base URL
const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://doantrang.online/v1/api';

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
    const token = config.skipAuth ? null : getAdminAccessToken();
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
    if (error.response?.status === 401 && !error.config?.skipAuthRedirect) {
      clearAdminSession();
      if (window.location.pathname !== '/') {
        window.location.href = '/';
      }
    }
    return Promise.reject(error);
  }
);

const publicRequest = { skipAuth: true, skipAuthRedirect: true };

// Auth endpoints
export const authAPI = {
  register: (email, password) =>
    apiClient.post('/auth/register', { email, password }, publicRequest),
  
  verifyOtp: (email, otp) =>
    apiClient.post('/auth/verify-otp', { email, otp }, publicRequest),

  sendLoginOtp: (email) =>
    apiClient.post('/auth/otp/send', { email }, publicRequest),

  verifyLoginOtp: (email, otp) =>
    apiClient.post('/auth/otp/verify', { email, otp }, publicRequest),

  verify2FA: (pendingToken, code) =>
    apiClient.post('/auth/2fa/verify', { pendingToken, code }, publicRequest),
  
  login: (email, password) =>
    apiClient.post('/auth/login', { email, password }, publicRequest),
  
  logout: () =>
    apiClient.post('/auth/logout'),
  
  refreshToken: (refreshToken) =>
    apiClient.post('/auth/refresh-token', { refreshToken }),
};

export const ordersAPI = {
  getAll: (params = {}) =>
    apiClient.get('/orders/staff', { params }),

  getById: (orderId) =>
    apiClient.get(`/orders/staff/${orderId}`),

  updateStatus: (orderId, status) =>
    apiClient.put(`/orders/staff/${orderId}/status`, { status }),

  getStats: () =>
    apiClient.get('/orders/staff/stats'),
};

export const warrantyAPI = {
  getClaimGroups: (params = {}) =>
    apiClient.get('/warranty-claims/grouped', { params }),

  getClaims: (params = {}) =>
    apiClient.get('/warranty-claims', { params }),

  updateClaimStatus: (claimId, status) =>
    apiClient.put(`/warranty-claims/${claimId}`, { status }),

  createClaimBySerial: (serialNumber, description) =>
    apiClient.post('/warranty-claims/by-serial', { serialNumber, description }),
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
  discontinueProduct: (id) => apiClient.put(`/catalogs/products/${id}/discontinue`),
  deleteProduct: (id) => apiClient.delete(`/catalogs/products/${id}`),
};

export const productItemAPI = {
  getAll: (params = {}) => apiClient.get('/product-items/list', { params }),
  getAllFull: (params = {}) => apiClient.get('/product-items', { params }),
  getByProduct: (productId) => apiClient.get(`/product-items/product/${productId}`),
  getById: (id) => apiClient.get(`/product-items/${id}`),
  create: (payload) => apiClient.post('/product-items', payload),
  update: (id, payload) => apiClient.put(`/product-items/${id}`, payload),
  toggleStatus: (id) => apiClient.put(`/product-items/${id}/toggle-status`),
  discontinue: (id) => apiClient.put(`/product-items/${id}/discontinue`),
  delete: (id) => apiClient.delete(`/product-items/${id}`),
  addStock: (id, quantity) => apiClient.post(`/product-items/${id}/add-stock`, null, { params: { quantity } }),
  reduceStock: (id, quantity) => apiClient.post(`/product-items/${id}/reduce-stock`, null, { params: { quantity } }),
  getDiscounted: (params = {}) => apiClient.get('/product-items/discounted', { params }),
  disableDiscount: (id) => apiClient.put(`/product-items/${id}/disable-discount`),
};

export const promotionsAPI = {
  getAll: () => apiClient.get('/promotions'),
  getActive: () => apiClient.get('/promotions/active'),
  getById: (id) => apiClient.get(`/promotions/${id}`),
  create: (payload) => apiClient.post('/promotions', payload),
  update: (id, payload) => apiClient.put(`/promotions/${id}`, payload),
  delete: (id) => apiClient.delete(`/promotions/${id}`),
  apply: (payload) => apiClient.post('/promotions/apply', payload),
  remove: (payload) => apiClient.delete('/promotions/apply', { data: payload }),
  getProductsByPromotion: (promotionId) => apiClient.get(`/promotions/${promotionId}/products`),
  getItemsByPromotion: (promotionId) => apiClient.get(`/promotions/${promotionId}/items`),
  getVariantsByProduct: (productId) => apiClient.get(`/product-items/variants/${productId}`),
  applyToItems: (payload) => apiClient.post('/promotions/apply-items', payload),
  removeFromItems: (productItemIds) => apiClient.delete('/promotions/apply-items', { data: productItemIds }),
};

export const usersAPI = {
  getAll: (params = {}) => apiClient.get('/users', { params }),
  getById: (id) => apiClient.get(`/users/${id}`),
  create: (payload) => apiClient.post('/users', payload),
  update: (id, payload) => apiClient.put(`/users/${id}`, payload),
  delete: (id) => apiClient.delete(`/users/${id}`),
  search: (keyword) => apiClient.get('/users/search', { params: { keyword } }),
  changePassword: (id, newPassword) => apiClient.post(`/users/${id}/change-password`, { newPassword }),
  ban: (id) => apiClient.put(`/users/${id}/ban`),
  unban: (id) => apiClient.put(`/users/${id}/unban`),
};

export const profileAPI = {
  getProfile: () => apiClient.get('/profile'),
  updateProfile: (payload) => apiClient.put('/profile', payload),
  changePassword: (payload) => apiClient.post('/profile/change-password', payload),
};

export const twoFactorAPI = {
  setup: () => apiClient.post('/auth/2fa/setup'),
  enable: (code) => apiClient.post('/auth/2fa/enable', { code }),
  disable: (code) => apiClient.post('/auth/2fa/disable', { code }),
  verify: (pendingToken, code) => apiClient.post('/auth/2fa/verify', { pendingToken, code }),
};

export const uploadAPI = {
  uploadUserAvatar: (file) => {
    const formData = new FormData();
    formData.append('file', file);
    return apiClient.post('/uploads/users', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      skipAuth: false,
    });
  },
  uploadProductImage: (file) => {
    const formData = new FormData();
    formData.append('file', file);
    return apiClient.post('/uploads/products', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      skipAuth: false,
    });
  },
};

export default apiClient;
