import { useAuth0 } from '@auth0/auth0-react';
import axios, { AxiosError, type AxiosRequestConfig } from 'axios';

export const useApiCaller = () => {
  const { getAccessTokenSilently, isAuthenticated } = useAuth0();

  const callApi = async <T = any>(
    path: string,
    requiresAuth: boolean = true,
    method: string = 'GET',
    body?: unknown
  ): Promise<T> => {
    const url = `${import.meta.env.VITE_API_BASE_URL}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (requiresAuth && isAuthenticated) {
      const token = await getAccessTokenSilently();
      headers['Authorization'] = `Bearer ${token}`;
    }

    const config: AxiosRequestConfig = {
      url,
      method,
      headers,
      data: body,
      withCredentials: true, // same as credentials: 'include'
    };

    try {
      const response = await axios.request<T>(config);
      return response.data;
    } catch (err) {
      const axiosError = err as AxiosError;
      const status = axiosError.response?.status ?? 'unknown';
      throw new Error(`API call failed with status ${status}`);
    }
  };

  return { callApi };
};
