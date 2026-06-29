<template>
  <div>
    <h2>💰 我的缴费</h2>
    <el-table :data="list" border stripe v-loading="loading" style="margin-top: 16px">
      <el-table-column prop="paymentId" label="ID" width="80" />
      <el-table-column prop="amount" label="金额(元)" width="100" />
      <el-table-column prop="lateFeePaid" label="滞纳金" width="90" />
      <el-table-column prop="channel" label="渠道" width="90">
        <template #default="{ row }">
          <el-tag :type="row.channel === 'ONLINE' ? 'success' : 'warning'" size="small">
            {{ row.channel === 'ONLINE' ? '线上' : '线下' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="paymentTime" label="缴费时间" width="160" />
      <el-table-column prop="transactionNo" label="流水号" min-width="200" />
    </el-table>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import billApi from '@/api/bill'
import paymentApi from '@/api/payment'

const list = ref([])
const loading = ref(false)

onMounted(async () => {
  loading.value = true
  try {
    const bills = (await billApi.list()).data.data || []
    const allPayments = []
    for (const bill of bills) {
      try {
        const res = await paymentApi.list(bill.billId)
        allPayments.push(...(res.data.data || []))
      } catch { /* ignore */ }
    }
    list.value = allPayments
  } finally { loading.value = false }
})
</script>
