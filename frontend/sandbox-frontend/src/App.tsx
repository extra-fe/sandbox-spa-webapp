import './App.css';
import { useAuth0 } from '@auth0/auth0-react';
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
        </header>
    </div>
    );
}
export default App;            
