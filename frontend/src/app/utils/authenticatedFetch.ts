export const authenticatedFetch = (url: string, options: RequestInit = {}) => {
  const authData = sessionStorage.getItem('auth');
  if (!authData) {
    throw new Error('No authentication data');
  }

  const { credentials } = JSON.parse(authData);
  const auth = btoa(`${credentials.username}:${credentials.password}`);

  return fetch(url, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Basic ${auth}`,
    },
  });
};