package com.example.orderservice.service;

import com.example.orderservice.model.Order;
import com.example.orderservice.repository.OrderRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;
    private final SnsClient snsClient;
    private final ObjectMapper objectMapper;

    @Value("${aws.sns.topic-arn}")
    private String snsTopicArn;

    @Transactional
    public Order createOrder(Order order) {
        order.setStatus(Order.OrderStatus.PENDING);
        Order savedOrder = orderRepository.save(order);
        
        // Publish order event to SNS
        publishOrderEvent(savedOrder, "ORDER_CREATED");
        
        log.info("Order created with ID: {}", savedOrder.getId());
        return savedOrder;
    }

    public Order getOrderById(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found with id: " + id));
    }

    public List<Order> getOrdersByUserId(Long userId) {
        return orderRepository.findByUserId(userId);
    }

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    @Transactional
    public Order updateOrderStatus(Long id, Order.OrderStatus status) {
        Order order = getOrderById(id);
        order.setStatus(status);
        Order updatedOrder = orderRepository.save(order);
        
        // Publish order event to SNS
        publishOrderEvent(updatedOrder, "ORDER_STATUS_UPDATED");
        
        log.info("Order {} status updated to {}", id, status);
        return updatedOrder;
    }

    private void publishOrderEvent(Order order, String eventType) {
        try {
            String message = objectMapper.writeValueAsString(order);
            
            PublishRequest publishRequest = PublishRequest.builder()
                    .topicArn(snsTopicArn)
                    .message(message)
                    .subject(eventType)
                    .build();
            
            snsClient.publish(publishRequest);
            log.info("Published {} event for order {}", eventType, order.getId());
        } catch (Exception e) {
            log.error("Failed to publish order event", e);
            // Don't fail the transaction if SNS publish fails
        }
    }
}
