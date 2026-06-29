<template>
  <div>
    <h2>📄 我的账单</h2>
    <el-form :inline="true" style="margin: 16px 0">
      <el-form-item label="状态">
        <el-select v-model="filters.status" clearable placeholder="全部" @change="fetchList">
          <el-option label="待缴费" value="PENDING" />
          <el-option label="已缴费" value="PAID" />
          <el-option label="已逾期" value="OVERDUE" />
        </el-select>
      </el-form-item>
    </el-form>

    <el-table :data="list" border stripe v-loading="loading">
      <el-table-column prop="billMonth" label="账期" width="100" />
      <el-table-column prop="totalUsage" label="用电量(度)" width="110" />
      <el-table-column label="阶梯用量" width="180">
        <template #default="{ row }">{{ row.tier1Usage }} / {{ row.tier2Usage }} / {{ row.tier3Usage }}</template>
      </el-table-column>
      <el-table-column prop="totalAmount" label="电费(元)" width="100" />
      <el-table-column prop="lateFee" label="滞纳金" width="90" />
      <el-table-column prop="status" label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'PAID' ? 'success' : row.status === 'OVERDUE' ? 'danger' : 'warning'" size="small">
            {{ { PENDING: '待缴', PAID: '已缴', OVERDUE: '逾期' }[row.status] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="dueDate" label="截止日" width="100" />
      <el-table-column label="操作" width="120">
        <template #default="{ row }">
          <el-button
            v-if="row.status !== 'PAID'"
            size="small" type="primary"
            @click="handlePay(row)"
          >缴费</el-button>
        </template>
      </el-table-column>
    </el-table>

    <!-- 缴费确认弹窗 -->
    <el-dialog v-model="payVisible" title="确认缴费" width="400px">
      <p>账单: {{ payForm.billMonth }}</p>
      <p>电费: {{ payForm.totalAmount }} 元</p>
      <p v-if="payForm.lateFee > 0">滞纳金: {{ payForm.lateFee }} 元</p>
      <p><strong>合计: {{ totalPay }} 元</strong></p>
      <template #footer>
        <el-button @click="payVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmPay" :loading="paying">确认缴费</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import billApi from '@/api/bill'
import paymentApi from '@/api/payment'

const list = ref([])
const loading = ref(false)
const filters = reactive({ status: null })
const payVisible = ref(false)
const paying = ref(false)
const payForm = ref({})
const totalPay = computed(() => (payForm.value.totalAmount || 0) + (payForm.value.lateFee || 0))

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try { list.value = (await billApi.list(filters)).data.data } finally { loading.value = false }
}

function handlePay(row) {
  payForm.value = row
  payVisible.value = true
}

async function confirmPay() {
  paying.value = true
  try {
    await paymentApi.pay({
      billId: payForm.value.billId,
      amount: payForm.value.totalAmount,
      channel: 'ONLINE'
    })
    ElMessage.success('缴费成功')
    payVisible.value = false
    fetchList()
  } finally { paying.value = false }
}
</script>
