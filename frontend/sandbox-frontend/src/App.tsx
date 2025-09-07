import { useState } from 'react';
import './App.css';
import { useAuth0 } from '@auth0/auth0-react';
import { useApiCaller } from './hooks/useApiCaller';

function App() {
    const {
    user,
    logout,
    loginWithRedirect,
    isAuthenticated,
    isLoading,
    } = useAuth0();
    const onClickLoginButton = () => {
      loginWithRedirect();
    };
    const onClickLogoutButton = () => {
      logout();
    };

    const [apiResponse, setApiResponse] = useState(null);
    const { callApi } = useApiCaller();

    const handleCallProtected = async () => {
      const data = await callApi('/api/protected');
      console.log(data);
      setApiResponse(data);
    };
  
    const handleCallGuest = async () => {
      const data = await callApi('/api/guest/connect-test', false);
      console.log(data);
      setApiResponse(data);
    };
    
    return (
    <div className="App">
        <header className="App-header">
        <button
            type="button"
            onClick={isAuthenticated ? onClickLogoutButton : onClickLoginButton}
        >
            {isAuthenticated ? 'logout' : 'login'}
        </button>
          <div>{isLoading ? 'LoadingNow' : (user?.name ?? 'unauthorized')}</div>

        <button
            type="button"
            onClick={handleCallGuest}
        >
            Call Guest API
        </button>

          { <button
              type="button"
              onClick={handleCallProtected}
              className="bg-green-300"
            >
            Call Protected API
          </button> 
          }

        {apiResponse && (
          <pre style={{ textAlign: 'left' }}>
            {JSON.stringify(apiResponse, null, 2)}
          </pre>
        )}

        </header>
    </div>
    );
}
export default App;   