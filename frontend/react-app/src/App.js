import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const JAVA_API = process.env.REACT_APP_JAVA_SERVICE_URL || 'http://localhost:8080';
const NODE_API = process.env.REACT_APP_NODEJS_SERVICE_URL || 'http://localhost:3000';

function App() {
  const [users, setUsers] = useState([]);
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [usersResponse, ordersResponse] = await Promise.all([
        axios.get(`${NODE_API}/api/users`),
        axios.get(`${JAVA_API}/api/orders`)
      ]);
      setUsers(usersResponse.data);
      setOrders(ordersResponse.data);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  const createUser = async () => {
    try {
      await axios.post(`${NODE_API}/api/users`, {
        name: 'Test User',
        email: `user${Date.now()}@example.com`,
        phone: '555-0100'
      });
      fetchData();
    } catch (error) {
      console.error('Error creating user:', error);
    }
  };

  const createOrder = async () => {
    if (users.length === 0) {
      alert('Please create a user first');
      return;
    }
    try {
      await axios.post(`${JAVA_API}/api/orders`, {
        userId: users[0].id,
        productName: 'Sample Product',
        quantity: 1,
        totalAmount: 99.99
      });
      fetchData();
    } catch (error) {
      console.error('Error creating order:', error);
    }
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>AWS Microservices Platform</h1>
        <p>Java + Node.js + React Demo</p>
      </header>

      <div className="container">
        <div className="section">
          <h2>Users Service (Node.js)</h2>
          <button onClick={createUser}>Create Test User</button>
          <div className="list">
            {users.length === 0 ? (
              <p>No users found</p>
            ) : (
              users.map(user => (
                <div key={user.id} className="item">
                  <strong>{user.name}</strong> - {user.email}
                </div>
              ))
            )}
          </div>
        </div>

        <div className="section">
          <h2>Orders Service (Java)</h2>
          <button onClick={createOrder}>Create Test Order</button>
          <div className="list">
            {orders.length === 0 ? (
              <p>No orders found</p>
            ) : (
              orders.map(order => (
                <div key={order.id} className="item">
                  <strong>{order.productName}</strong> - ${order.totalAmount} 
                  <span className={`status ${order.status.toLowerCase()}`}>
                    {order.status}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
