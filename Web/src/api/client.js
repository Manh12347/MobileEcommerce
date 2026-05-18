import axios from 'axios';

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

export default apiClient;
