package com.electric.billing.module.payment;

import com.electric.billing.common.R;
import com.electric.billing.entity.Payment;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/payment")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    /** 缴费 */
    @PostMapping
    public R<Payment> pay(@RequestBody Payment payment) {
        return R.ok(paymentService.pay(payment));
    }

    /** 缴费记录列表 — 可选按账单ID筛选 */
    @GetMapping("/list")
    public R<List<Payment>> list(@RequestParam(required = false) Long billId) {
        return R.ok(paymentService.listByBill(billId));
    }

    /** 缴费详情 */
    @GetMapping("/{id}")
    public R<Payment> get(@PathVariable Long id) {
        return R.ok(paymentService.getById(id));
    }
}
