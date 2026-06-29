package com.electric.billing.module.payment;

import com.electric.billing.common.R;
import com.electric.billing.entity.Payment;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/payment")
public class PaymentController {

    private final PaymentService paymentService;
    public PaymentController(PaymentService paymentService) { this.paymentService = paymentService; }

    @PostMapping
    public R<Payment> pay(@RequestBody Payment payment) { return R.ok(paymentService.pay(payment)); }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(required = false) Long billId) {
        return R.ok(paymentService.listByBill(page, pageSize, billId));
    }

    @GetMapping("/{id}")
    public R<Payment> get(@PathVariable Long id) { return R.ok(paymentService.getById(id)); }
}
