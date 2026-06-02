// ignore_for_file: constant_identifier_names

// API Configuration
// Frontend gọi vào backend server đã deploy

const String API_BASE_URL = 'https://doantrang.online/v1/api';
const String PRODUCTS_ENDPOINT = '/catalogs/products';
const String CATEGORIES_ENDPOINT = '/catalogs/categories';
const String PRODUCT_ITEMS_ENDPOINT = '/product-items';
const String CART_ENDPOINT = '/cart';
const String ORDERS_ENDPOINT = '/orders';
const String WARRANTIES_ENDPOINT = '/warranties';
const String WARRANTY_CLAIMS_ENDPOINT = '/warranty-claims';
const String GHN_BASE_URL =
    'https://dev-online-gateway.ghn.vn/shiip/public-api';
const String GHN_TOKEN = '487a9da5-58a4-11f1-a973-aee5264794df';
const String GHN_SHOP_ID = '200413';
const String GHN_FROM_NAME = 'Ecommerce Shop';
const String GHN_FROM_PHONE = '0900000000';
const String GHN_FROM_ADDRESS = '72 Thanh Thai';
const String GHN_FROM_WARD_NAME = 'Phuong 14';
const String GHN_FROM_DISTRICT_NAME = 'Quan 10';
const String GHN_FROM_PROVINCE_NAME = 'HCM';
const String GHN_RETURN_PHONE = '0900000000';
const String GHN_RETURN_ADDRESS = '72 Thanh Thai';
const String GHN_REQUIRED_NOTE = 'KHONGCHOXEMHANG';
const int GHN_DEFAULT_WEIGHT = 1200;
const int GHN_DEFAULT_LENGTH = 12;
const int GHN_DEFAULT_WIDTH = 12;
const int GHN_DEFAULT_HEIGHT = 12;
const int GHN_SERVICE_TYPE_ID = 2;
const int GHN_PICK_SHIFT = 2;

const String GOOGLE_OAUTH_SERVER_CLIENT_ID = String.fromEnvironment(
  'GOOGLE_OAUTH_SERVER_CLIENT_ID',
  defaultValue: '',
);

// Nếu cần đổi môi trường, cập nhật base URL tại đây.
