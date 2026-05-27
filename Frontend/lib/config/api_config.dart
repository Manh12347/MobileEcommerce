// API Configuration
// Frontend gọi vào backend server đã deploy

const String API_BASE_URL = 'https://doantrang.online/v1/api';
const String PRODUCTS_ENDPOINT = '/catalogs/products';
const String PRODUCT_ITEMS_ENDPOINT = '/product-items';
const String CART_ENDPOINT = '/cart';
const String ORDERS_ENDPOINT = '/orders';


const String GOOGLE_OAUTH_SERVER_CLIENT_ID = String.fromEnvironment(
  'GOOGLE_OAUTH_SERVER_CLIENT_ID',
  defaultValue: '',
);

// Nếu cần đổi môi trường, cập nhật base URL tại đây.
